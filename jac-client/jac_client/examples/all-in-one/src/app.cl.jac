#
# Combined example: auth + routing + CSS styling + asset serving + nested folder imports
#
import from react { useState, useEffect, useRef }
import from "@jac-client/utils" {
    Router,
    Routes,
    Route,

}

# Pure CSS + asset-in-CSS example
import ".styles.css";

 # Login Page
import from .pages.loginPage { LoginPage }

# Signup Page
import from .pages.signupPage { SignupPage }

# Home page demonstrating CSS styling + direct asset usage + basic walkers
import from .pages.homePage { HomePage }

# Simple 404 page
import from .pages.notFound { NotFound }

# Navigation component with active link styling and auth
import from .components.navigation { Navigation }

# Page showing nested imports from different folders
import from .pages.nestedDemo { NestedImportsDemo }

import from .pages.FeaturesTest { FeaturesTest }

import from .pages.LandingPage { LandingPage }

import from .pages.BudgetPlanner { BudgetPlanner }

# Context provider
cl import from .context.BudgetContext { BudgetProvider }


# Main app wrapped in Router (same API as with-router/ example)
def:pub app -> any {
    return <Router>
        <div
            style={{"fontFamily": "system-ui, -apple-system, sans-serif"}}
        >
            <Navigation />
            <div
                style={{
                    "maxWidth": "960px",
                    "margin": "0 auto",
                    "padding": "0 1rem 3rem 1rem"
                }}
            >
                <Routes>
                    <Route
                        path="/"
                        element={<HomePage />}
                    />
                    <Route
                        path="/login"
                        element={<LoginPage />}
                    />
                    <Route
                        path="/signup"
                        element={<SignupPage />}
                    />
                    <Route
                        path="/nested"
                        element={<NestedImportsDemo />}
                    />
                    <Route
                        path="/features-test"
                        element={<FeaturesTest />}
                    />
                    <Route
                        path="/landing"
                        element={<LandingPage />}
                    />
                    <Route
                        path="/budget-planner"
                        element={<BudgetProvider>
                            <BudgetPlanner />
                        </BudgetProvider>}
                    />
                    <Route
                        path="*"
                        element={<NotFound />}
                    />
                </Routes>
            </div>
        </div>
    </Router>;
}
