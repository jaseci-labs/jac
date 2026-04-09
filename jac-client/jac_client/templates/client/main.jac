"""Main entry point for {{name}}."""

# Client-side imports (useState is auto-injected when using `has` variables)
cl import from react { useEffect }
cl import from .components.Button { Button }

# Client-side component
cl {
    def:pub app -> any {
        has count: int = 0;

        useEffect(lambda { console.log("Count updated:", count);}, [count]);

        return
            <div style={{padding: "2rem", fontFamily: "Arial, sans-serif"}}>
                <h1>
                    Hello, World!
                </h1>
                <p>
                    Count:{count}
                </p>
                <div style={{display: "flex", gap: "1rem", marginTop: "1rem"}}>
                    <Button
                        label="Increment"
                        onClick={lambda { count = count + 1;}}
                        variant="primary"
                    />
                    <Button
                        label="Reset"
                        onClick={lambda { count = 0;}}
                        variant="secondary"
                    />
                </div>
            </div>;
    }
}
