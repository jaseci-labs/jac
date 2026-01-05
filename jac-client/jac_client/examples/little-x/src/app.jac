import datetime;
cl import from lodash { * as _ }
cl import from antd { Button, Input, Card, Typography, Space }
cl import from pluralize { default as pluralize }
cl import from 'react-animated-components' { Rotate }

node Profile {
    has username: str = "";

    can update with update_profile entry {
        self.username = visitor.new_username;
        report self ;
    }

    can get with get_profile entry {
        follwers = [
            {"id": jid(i), "username": i.username} for i in [self-->(`?Profile)]
        ];
        report {"user": self, "followers": follwers} ;
    }

    can follow with follow_request entry {
        current_profile = [root-->(`?Profile)];
        current_profile[0] +>: Follow() :+> self;
        report self ;
    }

    can un_follow with un_follow_request entry {
        current_profile = [root-->(`?Profile)];
        follow_edge = [edge current_profile[0]->:Follow:->self];
        del follow_edge[0] ;
        report self ;
    }
}

obj TweetInfo {
    has username: str,
        id: str,
        content: str,
        embedding: list,
        likes: list,
        comments: list;
}

node Tweet {
    has content: str,
        embedding: list,
        created_at: str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S");

    can update with update_tweet exit {
        self.content = visitor.updated_content;
        report self ;
    }

    can delete with remove_tweet exit {
        del self ;
        disengage;
    }

    can like_tweet with like_tweet entry {
        current_profile = [root-->(`?Profile)];
        self +>: Like() :+> current_profile[0];
        report self ;
    }

    can remove_like with remove_like entry {
        current_profile = [root-->(`?Profile)];
        like_edge = [edge self->:Like:->current_profile[0]];
        del like_edge[0] ;
        report self ;
    }

    can comment with comment_tweet entry {
        current_profile = [root-->(`?Profile)];
        comment_node = current_profile[0] +>: Post() :+> Comment(
            content=visitor.content
        );
        grant(comment_node[0], level=ConnectPerm);
        self ++> comment_node[0];
        report comment_node[0] ;
    }

    def get_info -> TweetInfo {
        return TweetInfo(
            username=[self<-:Post:<-][0].username,
            id=jid(self),
            content=self.content,
            embedding=self.embedding,
            likes=[i.username for i in [self->:Like:->]],
            comments=[
                {
                    "username": [i<--(`?Profile)][0].username,
                    "id": jid(i),
                    "content": i.content
                } for i in [self-->(`?Comment)]
            ]
        );
    }

    can get with load_feed entry {
        tweet_info = self.get_info();
        visitor.results.append({"Tweet_Info": tweet_info});
    }
}

node Comment {
    has content: str;

    can update with update_comment entry {
        self.content = visitor.updated_content;
        report self ;
    }

    can delete with remove_comment entry {
        del self ;
        disengage;
    }
}

edge Follow {}

edge Like {}

edge Post {}

walker visit_profile {
    can visit_profile with `root entry {
        visit [-->(`?Profile)] else {
            new_profile = here ++> Profile();
            grant(new_profile[0], level=ConnectPerm);
            visit new_profile;
        }
    }
}

walker update_profile(visit_profile) {
    has new_username: str;
}

walker get_profile(visit_profile) {}

walker load_user_profiles {
    can load_profiles with `root entry {
        self.profiles: list = [];
        for each_root in allroots() {
            profile = [each_root-->(`?Profile)][0];
            self.profiles.append({"name": profile.username, "id": jid(profile)});
        }
    }

    can report_profiles with exit {
        report self.profiles ;
    }
}

walker follow_request {}

walker un_follow_request {}

walker create_tweet(visit_profile) {
    has content: str;

    can tweet with Profile entry {
        tweet_node = here +>: Post() :+> Tweet(content=self.content, embedding=[]);
        grant(tweet_node[0], level=ConnectPerm);
        report tweet_node ;
    }
}

walker update_tweet {
    has updated_content: str;
}

walker remove_tweet {}

walker like_tweet {}

walker remove_like {}

walker comment_tweet {
    has content: str;
}

walker update_comment {
    has updated_content: str;
}

walker remove_comment {}

walker load_feed(visit_profile) {
    has search_query: str = "",
        results: list = [];

    can load with Profile entry {
        visit [-->(`?Tweet)];
        for user_node in [->:Follow:->(`?Profile)] {
            visit [user_node-->(`?Tweet)];
        }
    }

    can report_feed with exit {
        report self.results ;
    }
}

# Client-side UI Components (marked with 'cl' for browser execution)
# ===================================================================

# Manual routing functions removed - now using reactive createRouter

# Shared data model for client/server
cl obj ClientTweet {
    has username: str = "",
        id: str = "",
        content: str = "",
        likes: list = [],
        comments: list = [];
}

cl obj ClientProfile {
    has username: str = "",
        id: str = "";
}

# UI Components - Render a single tweet card
cl def TweetCard(tweet: ClientTweet) -> any {
    return <div
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
            style={{"fontWeight": "bold", "marginBottom": "80px"}}
        >
            @{tweet.username}
        </div>
        <div
            class="tweet-content"
            style={{"marginBottom": "12px"}}
        >
            {tweet.content}
        </div>
        <div
            class="tweet-actions"
            style={{"display": "flex", "gap": "15px"}}
        >
            <button
                onclick={like_tweet_action(tweet.id)}
                style={{"padding": "5px 10px", "cursor": "pointer"}}
            >
                Like ({tweet.likes.length})
            </button>
            <button
                style={{"padding": "5px 10px"}}
            >
                Comment ({tweet.comments.length})
            </button>
        </div>
    </div>;
}

# Handle liking a tweet - calls server walker directly
# The compiler automatically transforms this to __jacCallFunction at compile time!
cl async def like_tweet_action(
    tweet_id: str
) -> any {
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
cl def FeedView(tweets: list) -> any {
    return <div
        class="feed-container"
        style={{"maxWidth": "600px", "margin": "0 auto", "fontFamily": "sans-serif"}}
    >
        <div
            class="feed-header"
            style={{"padding": "20px", "borderBottom": "1px solid #e1e8ed"}}
        >
            <h1
                style={{"margin": "0"}}
            >
                LittleX Feed
            </h1>
        </div>
        <div class="feed-content">
            {[TweetCard(tweet) for tweet in tweets]}
        </div>
    </div>;
}

# Render login form
cl def LoginForm -> any {
    suggestions = ['good luck', 'have fun', 'enjoy the ride'];
    randomSuggestion = _.sample(suggestions);
    result = "Good luck with your journey!";
    return <Card
        title="Login to LittleX"
        style={{"maxWidth": "400px", "margin": "50px auto"}}
    >
        <Card.Meta
            title={randomSuggestion}
            description={result}
        />
        <form
            onSubmit={handle_login}
        >
            <div
                style={{"marginBottom": "15px"}}
            >
                <label
                    style={{"display": "block", "marginBottom": "5px"}}
                >
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
            <div
                style={{"marginBottom": "15px"}}
            >
                <label
                    style={{"display": "block", "marginBottom": "5px"}}
                >
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
            <Button
                htmlType="submit"
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
            </Button>
            <Button
                color="default"
                variant="dashed"
            >
                Dashed
            </Button>
            <Button
                color="default"
                variant="filled"
            >
                Filled
            </Button>
            <Button
                color="default"
                variant="text"
            >
                Text
            </Button>
            <Button
                color="default"
                variant="link"
            >
                Link
            </Button>
        </form>
        <div
            style={{"marginTop": "15px", "textAlign": "center"}}
        >
            <Link href="/signup">
                Don't have an account? Sign up
            </Link>
        </div>
    </Card>;
}

# Handle login form submission
cl async def handle_login(event: any) -> None {
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
cl def SignupForm -> any {
    return <div
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
        <Typography.Title
            level={2}
            style={{"marginTop": "0"}}
        >
            Sign Up for LittleX
        </Typography.Title>
        <form
            onSubmit={handle_signup}
        >
            <div
                style={{"marginBottom": "15px"}}
            >
                <label
                    style={{"display": "block", "marginBottom": "5px"}}
                >
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
            <div
                style={{"marginBottom": "15px"}}
            >
                <label
                    style={{"display": "block", "marginBottom": "5px"}}
                >
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
            <div
                style={{"marginBottom": "15px"}}
            >
                <label
                    style={{"display": "block", "marginBottom": "5px"}}
                >
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
        <div
            style={{"marginTop": "15px", "textAlign": "center"}}
        >
            <Link href="/login">
                Already have an account? Login
            </Link>
        </div>
    </div>;
}

# Navigation helper functions removed - using Link component and navigate() directly

# Handle signup form submission
cl async def handle_signup(event: any) -> None {
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
cl def logout_action -> None {
    jacLogout();
    navigate("/login");
}

# Main App component with declarative router
cl def:pub App -> any {
    # Create routes array manually (workaround for JS compiler bug with named args)
    login_route = {
        "path": "/login",
        "component": lambda   -> any{ return LoginForm(); } ,
        "guard": None
    };
    signup_route = {
        "path": "/signup",
        "component": lambda   -> any{ return SignupForm(); } ,
        "guard": None
    };
    home_route = {
        "path": "/home",
        "component": lambda   -> any{ return HomeView(); } ,
        "guard": jacIsLoggedIn
    };
    profile_route = {
        "path": "/profile",
        "component": lambda   -> any{ return ProfileView(); } ,
        "guard": jacIsLoggedIn
    };

    routes = [login_route, signup_route, home_route, profile_route];
    router = initRouter(routes, "/login");

    # Get current path for navbar
    currentPath = router.path();

    return <div class="app-container">
        {build_nav_bar(currentPath)}
        <Rotate>
            <span>
                😂
            </span>
        </Rotate>
        {router.render()}
    </div>;
}

# Helper to build navigation bar
cl def build_nav_bar(route: str) -> any {
    if not jacIsLoggedIn() or route == "/login" or route == "/signup" {
        return None;
    }
    return <nav
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
                onClick={logout_action}
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
cl def HomeView -> any {
    if not jacIsLoggedIn() {
        navigate("/login");
        return <div></div>;
    }

    return <div
        style={{"textAlign": "center", "padding": "50px", "fontFamily": "sans-serif"}}
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
cl def ProfileView -> any {
    if not jacIsLoggedIn() {
        navigate("/login");
        return <div></div>;
    }
    return <div
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

# Main SPA entry point - simplified with reactive routing
cl def:pub jac_app -> any {
    return App();
}
