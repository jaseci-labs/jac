"""Test declarative routing system."""

cl import from "@jac/runtime" { createRouter, Route, Link, navigate, createSignal, }

cl {
    # Mock components for testing
    def HomePage()  -> JsxElement {
        return <div id="home-page">
            Home Page
        </div>;
    }

    def AboutPage()  -> JsxElement {
        return <div id="about-page">
            About Page
        </div>;
    }

    def ProfilePage()  -> JsxElement {
        return <div id="profile-page">
            Profile Page
        </div>;
    }

    def LoginPage()  -> JsxElement {
        return <div id="login-page">
            Login Page
        </div>;
    }

    # Guard function
    def requireAuth()  -> bool {
        # Mock auth check
        return True;
    }

    # Test 1: Basic router creation and rendering
    def test_router_basic()  -> dict {
        router = createRouter(
            [
                Route(path="/home", component=HomePage),
                Route(path="/about", component=AboutPage),

            ],
            defaultRoute="/home"
        );

        # Get initial component
        initialComponent = router.render();

        return {
            "hasRouter": router != None,
            "hasRenderMethod": router.render != None,
            "hasNavigateMethod": router.navigate != None,
            "hasPathSignal": router.path != None
        };
    }

    # Test 2: Router navigation
    def test_router_navigation()  -> dict {
        router = createRouter(
            [
                Route(path="/home", component=HomePage),
                Route(path="/about", component=AboutPage),
                Route(path="/profile", component=ProfilePage),

            ],
            defaultRoute="/home"
        );

        # Initial route
        initialPath = router.path()();

        # Navigate to about
        router.navigate("/about");
        aboutPath = router.path()();

        # Navigate to profile
        router.navigate("/profile");
        profilePath = router.path()();

        return {
            "initialPath": initialPath,
            "aboutPath": aboutPath,
            "profilePath": profilePath
        };
    }

    # Test 3: Route guards
    def test_router_guards()  -> dict {
        router = createRouter(
            [
                Route(path="/home", component=HomePage),
                Route(path="/profile", component=ProfilePage, guard=requireAuth),

            ],
            defaultRoute="/home"
        );

        # Navigate to guarded route
        router.navigate("/profile");

        return {"currentPath": router.path()()};
    }

    # Test 4: Link component generation
    def test_link_component()  -> JsxElement {
        link = Link("/about", "Go to About");

        return {"hasLink": link != None, "isJSX": link.tag == "a"};
    }

    # Test 5: 404 handling
    def test_router_404()  -> dict {
        router = createRouter(
            [
                Route(path="/home", component=HomePage),
                Route(path="/about", component=AboutPage),

            ],
            defaultRoute="/home"
        );

        # Navigate to non-existent route
        router.navigate("/nonexistent");
        component = router.render();

        return {"currentPath": router.path()(), "has404": component != None};
    }

    # Test entry point
    def test_all_router_features()  -> dict {
        return {
            "basic": test_router_basic(),
            "navigation": test_router_navigation(),
            "guards": test_router_guards(),
            "404": test_router_404()
        };
    }
}
