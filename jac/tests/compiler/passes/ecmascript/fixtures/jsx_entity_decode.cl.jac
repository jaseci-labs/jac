"""Test that HTML entities in JSX text and attributes are decoded per JSX spec."""

cl {
    def:pub App() -> Any {
        return <div title="A &amp; B">
            Before &gt; After &amp; More
            Decimal &#62; and Hex &#x3e; refs
        </div>;
    }
}
