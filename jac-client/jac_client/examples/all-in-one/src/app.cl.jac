# Budget Planner - All-in-One JAC Example
# Entry point demonstrating all JAC-Client features with routing

# React Router imports
cl import from "@jac-client/utils" {
    Router,
    Routes,
    Route,
    Link,

}
# Page imports
cl import from .pages.LandingPage { LandingPage }
cl import from .pages.BudgetPlanner { BudgetPlanner }
cl import from .pages.FeaturesTest { FeaturesTest }

# Context provider
cl import from .context.BudgetContext { BudgetProvider }

# Global styles
cl import ".global.css";


cl def:pub app() -> any {
    return <Router>
        <Routes>
            <Route path="/" element={<LandingPage />} />
            <Route
                path="/app"
                element={
                    <BudgetProvider>
                        <BudgetPlanner />
                    </BudgetProvider>
                }
            />
            <Route path="/features" element={<FeaturesTest />} />
        </Routes>
    </Router>;
}
