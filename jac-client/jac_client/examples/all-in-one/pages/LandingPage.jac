# Landing Page - Ledgerly Brand
# Professional landing page with hero, features, and CTA sections
# Demonstrates: routing with Link, dark theme design, responsive layout
cl import from "@jac/runtime" {
    Link,
}

cl {
    def:pub LandingPage -> any {
        return
            <div className="landing-container">
                <section className="hero-section">
                    <h1 className="brand-name">
                        Ledgerly
                    </h1>
                    <p className="tagline">
                        Know your real income
                    </p>
                    <h2 className="headline">
                        Track Business & Personal Finances Separately
                    </h2>
                    <p className="subheadline">
                        Built for freelancers who need to see their true incomeafter taxes and business expenses.
                    </p>
                    <div
                        style={{
                            "display": "flex",
                            "gap": "15px",
                            "justifyContent": "center"
                        }}
                    >
                        <Link to="/app">
                            <button className="cta-button">
                                Let's Plan
                            </button>
                        </Link>
                        <Link to="/features">
                            <button
                                className="cta-button"
                                style={{
                                    "backgroundColor": "#8b5cf6",
                                    "border": "2px solid #8b5cf6"
                                }}
                            >
                                Test Features
                            </button>
                        </Link>
                    </div>
                </section>
                <section className="features-section">
                    <h2 className="features-title">
                        Built for Freelancers
                    </h2>
                    <div className="features-grid">
                        <div className="feature-card">
                            <div className="feature-icon">
                                💼
                            </div>
                            <h3 className="feature-title">
                                Business vs Personal
                            </h3>
                            <p className="feature-description">
                                Tag every transaction as business or personal.See your income streams separately and understand where your money really comes from.
                            </p>
                        </div>
                        <div className="feature-card">
                            <div className="feature-icon">
                                📊
                            </div>
                            <h3 className="feature-title">
                                Auto Tax Reserve
                            </h3>
                            <p className="feature-description">
                                Automatically calculate 20% tax reserve on business income.Know your true net profit after taxes without surprises.
                            </p>
                        </div>
                        <div className="feature-card">
                            <div className="feature-icon">
                                🏷️
                            </div>
                            <h3 className="feature-title">
                                Client Tagging
                            </h3>
                            <p className="feature-description">
                                Tag business income by client name. Track which clientsare generating the most revenue for your business.
                            </p>
                        </div>
                    </div>
                </section>
                <section className="cta-section">
                    <h2 className="cta-section-title">
                        Ready to know your real income?
                    </h2>
                    <p className="cta-section-text">
                        Start tracking your freelance finances the smart way.
                    </p>
                    <div
                        style={{
                            "display": "flex",
                            "gap": "15px",
                            "justifyContent": "center"
                        }}
                    >
                        <Link to="/app">
                            <button className="cta-button">
                                Get Started Free
                            </button>
                        </Link>
                        <Link to="/features">
                            <button
                                className="cta-button"
                                style={{
                                    "backgroundColor": "#8b5cf6",
                                    "border": "2px solid #8b5cf6"
                                }}
                            >
                                Explore Features
                            </button>
                        </Link>
                    </div>
                </section>
            </div>;
    }
}
