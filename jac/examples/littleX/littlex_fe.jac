cl import from "@jac/runtime" {
    jacLogin,
    jacLogout,
    jacSignup,
    createRouter,
    Route,
    Link,
    navigate,
    createState,
}

cl {
    # Reactive state management
    glob _state = createState({"tweets": [], "loading": False});
    glob appState = _state[0];
    glob setAppState = _state[1];

    # Shared data model for client/server
    obj ClientTweet {
        has username: str = "",
            id: str = "",
            content: str = "",
            likes: list = [],
            comments: list = [];
    }

    obj ClientProfile {
        has username: str = "",
            id: str = "";
    }

    # UI Components - Render a single tweet card
    def TweetCard(tweet: ClientTweet) -> JsxElement {
        return
            <div
                class="tweet-card"
                style={{
                    "border": "1px solid #e1e8ed",
                    "padding": "15px",
                    "margin": "10px 0",
                    "borderRadius": "8px"
                }}
            >
                <div
                    class="tweet-header"
                    style={{"fontWeight": "bold", "marginBottom": "8px"}}
                >
                    @{tweet.username}
                </div>
                <div class="tweet-content" style={{"marginBottom": "12px"}}>
                    {tweet.content}
                </div>
                <div class="tweet-actions" style={{"display": "flex", "gap": "15px"}}>
                    <button
                        onclick={like_tweet_action(tweet.id)}
                        style={{"padding": "5px 10px", "cursor": "pointer"}}
                    >
                        Like ({tweet.likes.length})
                    </button>
                    <button style={{"padding": "5px 10px"}}>
                        Comment ({tweet.comments.length})
                    </button>
                </div>
            </div>;
    }

    # Handle liking a tweet - calls server walker directly
    # The compiler automatically transforms this to __jacCallFunction at compile time!
    async def like_tweet_action(tweet_id: str) -> JsxElement {
        try {
            result = await like_tweet(tweet_id);
            print("Tweet liked:", result);
            # Re-render feed after like
            window.location.reload();
        } except Exception as e {
            print("Error liking tweet:", e);
        }
    }

    # Render the main feed view
    def FeedView(tweets: list) -> JsxElement {
        return
            <div
                class="feed-container"
                style={{
                    "maxWidth": "600px",
                    "margin": "0 auto",
                    "fontFamily": "sans-serif"
                }}
            >
                <div
                    class="feed-header"
                    style={{"padding": "20px", "borderBottom": "1px solid #e1e8ed"}}
                >
                    <h1 style={{"margin": "0"}}>
                        LittleX Feed
                    </h1>
                </div>
                <div class="feed-content">
                    {[TweetCard(tweet) for tweet in tweets]}
                </div>
            </div>;
    }

    # Render login form
    def LoginForm -> JsxElement {
        return
            <div
                class="login-container"
                style={{
                    "maxWidth": "400px",
                    "margin": "50px auto",
                    "padding": "20px",
                    "border": "1px solid #e1e8ed",
                    "borderRadius": "8px",
                    "fontFamily": "sans-serif"
                }}
            >
                <h2 style={{"marginTop": "0"}}>
                    Login to LittleX
                </h2>
                <form onsubmit={handle_login}>
                    <div style={{"marginBottom": "15px"}}>
                        <label style={{"display": "block", "marginBottom": "5px"}}>
                            Username:
                        </label>
                        <input
                            type="text"
                            id="username"
                            style={{
                                "width": "100%",
                                "padding": "8px",
                                "boxSizing": "border-box"
                            }}
                        />
                    </div>
                    <div style={{"marginBottom": "15px"}}>
                        <label style={{"display": "block", "marginBottom": "5px"}}>
                            Password:
                        </label>
                        <input
                            type="password"
                            id="password"
                            style={{
                                "width": "100%",
                                "padding": "8px",
                                "boxSizing": "border-box"
                            }}
                        />
                    </div>
                    <button
                        type="submit"
                        style={{
                            "width": "100%",
                            "padding": "10px",
                            "backgroundColor": "#1da1f2",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "4px",
                            "cursor": "pointer"
                        }}
                    >
                        Login
                    </button>
                </form>
                <div style={{"marginTop": "15px", "textAlign": "center"}}>
                    <Link href="/signup">
                        Don't have an account? Sign up
                    </Link>
                </div>
            </div>;
    }

    # Handle login form submission
    async def handle_login(event: any) -> None {
        event.preventDefault();
        username = document.getElementById("username").value;
        password = document.getElementById("password").value;
        success = await jacLogin(username, password);
        if success {
            navigate("/home");
        } else {
            alert("Login failed. Please try again.");
        }
    }

    # Render signup form
    def SignupForm -> JsxElement {
        return
            <div
                class="signup-container"
                style={{
                    "maxWidth": "400px",
                    "margin": "50px auto",
                    "padding": "20px",
                    "border": "1px solid #e1e8ed",
                    "borderRadius": "8px",
                    "fontFamily": "sans-serif"
                }}
            >
                <h2 style={{"marginTop": "0"}}>
                    Sign Up for LittleX
                </h2>
                <form onsubmit={handle_signup}>
                    <div style={{"marginBottom": "15px"}}>
                        <label style={{"display": "block", "marginBottom": "5px"}}>
                            Username:
                        </label>
                        <input
                            type="text"
                            id="signup-username"
                            required
                            style={{
                                "width": "100%",
                                "padding": "8px",
                                "boxSizing": "border-box"
                            }}
                        />
                    </div>
                    <div style={{"marginBottom": "15px"}}>
                        <label style={{"display": "block", "marginBottom": "5px"}}>
                            Password:
                        </label>
                        <input
                            type="password"
                            id="signup-password"
                            required
                            style={{
                                "width": "100%",
                                "padding": "8px",
                                "boxSizing": "border-box"
                            }}
                        />
                    </div>
                    <div style={{"marginBottom": "15px"}}>
                        <label style={{"display": "block", "marginBottom": "5px"}}>
                            Confirm Password:
                        </label>
                        <input
                            type="password"
                            id="signup-password-confirm"
                            required
                            style={{
                                "width": "100%",
                                "padding": "8px",
                                "boxSizing": "border-box"
                            }}
                        />
                    </div>
                    <button
                        type="submit"
                        style={{
                            "width": "100%",
                            "padding": "10px",
                            "backgroundColor": "#1da1f2",
                            "color": "white",
                            "border": "none",
                            "borderRadius": "4px",
                            "cursor": "pointer"
                        }}
                    >
                        Sign Up
                    </button>
                </form>
                <div style={{"marginTop": "15px", "textAlign": "center"}}>
                    <Link href="/login">
                        Already have an account? Login
                    </Link>
                </div>
            </div>;
    }

    # Handle signup form submission
    async def handle_signup(event: any) -> None {
        event.preventDefault();
        username = document.getElementById("signup-username").value;
        password = document.getElementById("signup-password").value;
        password_confirm = document.getElementById("signup-password-confirm").value;
        # Client-side validation
        if password != password_confirm {
            alert("Passwords do not match!");
            return;
        }
        if username.length < 3 {
            alert("Username must be at least 3 characters long.");
            return;
        }
        if password.length < 6 {
            alert("Password must be at least 6 characters long.");
            return;
        }
        # Use runtime auth function - no need to know about /user/register endpoint!
        result = await jacSignup(username, password);
        if result["success"] if "success" in result else False {
            alert("Account created successfully! Welcome to LittleX!");
            navigate("/home");
        } else {
            alert(result["error"] if "error" in result else "Signup failed");
        }
    }

    # Handle logout
    def logout_action -> None {
        jacLogout();
        navigate("/login");
    }

    # Main App component with declarative router
    def App -> JsxElement {
        # Create routes array manually (workaround for JS compiler bug with named args)
        login_route = {
            "path": "/login",
            "component": lambda -> JsxElement { return LoginForm(); },
            "guard": None
        };
        signup_route = {
            "path": "/signup",
            "component": lambda -> JsxElement { return SignupForm(); },
            "guard": None
        };
        home_route = {
            "path": "/home",
            "component": lambda -> JsxElement { return HomeView(); },
            "guard": jacIsLoggedIn
        };
        profile_route = {
            "path": "/profile",
            "component": lambda -> JsxElement { return ProfileView(); },
            "guard": jacIsLoggedIn
        };

        routes = [login_route, signup_route, home_route, profile_route];
        router = createRouter(routes, "/login");

        # Get current path for navbar
        currentPath = router.path();

        return
            <div class="app-container">
                {build_nav_bar(currentPath)}{router.render()}
            </div>;
    }

    # Helper to build navigation bar
    def build_nav_bar(route: str) -> Any {
        if not jacIsLoggedIn() or route == "/login" or route == "/signup" {
            return None;
        }
        return
            <nav
                style={{
                    "backgroundColor": "#1da1f2",
                    "padding": "15px",
                    "marginBottom": "20px"
                }}
            >
                <div
                    style={{
                        "maxWidth": "600px",
                        "margin": "0 auto",
                        "display": "flex",
                        "gap": "20px",
                        "alignItems": "center"
                    }}
                >
                    <Link href="/home">
                        <span
                            style={{
                                "color": "white",
                                "textDecoration": "none",
                                "fontWeight": "bold"
                            }}
                        >
                            Home
                        </span>
                    </Link>
                    <Link href="/profile">
                        <span
                            style={{
                                "color": "white",
                                "textDecoration": "none",
                                "fontWeight": "bold"
                            }}
                        >
                            Profile
                        </span>
                    </Link>
                    <button
                        onclick={logout_action}
                        style={{
                            "marginLeft": "auto",
                            "padding": "5px 15px",
                            "backgroundColor": "white",
                            "color": "#1da1f2",
                            "border": "none",
                            "borderRadius": "4px",
                            "cursor": "pointer",
                            "fontWeight": "bold"
                        }}
                    >
                        Logout
                    </button>
                </div>
            </nav>;
    }

    # Home view - simplified for testing reactive routing
    def HomeView -> JsxElement {
        if not jacIsLoggedIn() {
            navigate("/login");
            return
                <div></div>;
        }

        return
            <div
                style={{
                    "textAlign": "center",
                    "padding": "50px",
                    "fontFamily": "sans-serif"
                }}
            >
                <h1>
                    Home Feed
                </h1>
                <p>
                    Welcome to LittleX! This is the home page.
                </p>
                <p>
                    The reactive router is working!
                </p>
            </div>;
    }

    # Profile view
    def ProfileView -> JsxElement {
        if not jacIsLoggedIn() {
            navigate("/login");
            return
                <div></div>;
        }
        return
            <div
                class="profile-container"
                style={{
                    "maxWidth": "600px",
                    "margin": "20px auto",
                    "padding": "20px",
                    "fontFamily": "sans-serif"
                }}
            >
                <h1>
                    Profile
                </h1>
                <div
                    style={{
                        "padding": "15px",
                        "border": "1px solid #e1e8ed",
                        "borderRadius": "8px"
                    }}
                >
                    <p>
                        Profile information will be displayed here.
                    </p>
                </div>
            </div>;
    }
}
