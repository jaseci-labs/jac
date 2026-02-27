"""Exposes BUG: Quote characters in JSX text content produce invalid JS.

The transpiler outputs JSX text containing quote characters as ""text""
(double-double-quoted) instead of properly escaped strings, which Vite
and Rollup reject with "Expected ',', got 'ident'".
"""

cl {
    def:pub app() -> any {
        return (
            <div>
                <h1>Results</h1>
                <p>"Try: show all to reset"</p>
            </div>
        );
    }
}
