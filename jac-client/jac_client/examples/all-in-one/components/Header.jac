# Header component
# Demonstrates: simple component, CSS classes

cl {
    def:pub Header() -> any {
        return <header className="header">
            <div className="header-content">
                <h1 className="header-title">Budget Planner</h1>
                <p className="header-subtitle">Track your income and expenses</p>
            </div>
        </header>;
    }
}
